open Belt;

let parseFeed = payload =>
  Decoders_bs.Decode.decode_value(Decode_feed.decode_feed, payload);

let getFeed = (~token=?, user) => {
  let endpoint = {j|https://gh-feed.now.sh/api?user=$(user)|j};
  let endpoint =
    switch (token) {
    | None => endpoint
    | Some(token) => {j|$(endpoint)&token=$(token)|j}
    };
  Request.request_json(endpoint)
  |> Js.Promise.(then_(payload => resolve(parseFeed(payload))));
};

module ReactCache = {
  /* : {
       type resource('input, 'value);
       type hash;

       [@bs.module "react-cache"]
       external createResource: ('i => Js.Promise.t('v)) => resource('i, 'v) =
         "unstable_createResource";
       let createResourceWithCustomHash:
         ('i => Js.Promise.t('v), 'i => hash) => resource('i, 'v);

       [@bs.send] external read: (resource('i, 'v), 'i) => 'v = "";

       [@bs.send] external preload: (resource('i, 'v), 'i) => unit = "";
     }  */

  type resource('input, 'value);
  type hash = [ | `String(string) | `Int(int)];

  [@bs.module "react-cache"]
  external createResource: ('i => Js.Promise.t('v)) => resource('i, 'v) =
    "unstable_createResource";

  [@bs.module "react-cache"]
  external createResourceWithCustomHash:
    ('i => Js.Promise.t('v), 'i => string) => resource('i, 'v) =
    "unstable_createResource";

  let createResourceWithCustomHash = (fetch, hashInput) => {
    createResourceWithCustomHash(fetch, i =>
      switch (hashInput(i)) {
      | `String(s) => s
      | `Int(n) => string_of_int(n)
      }
    );
  };

  [@bs.send] external read: (resource('i, 'v), 'i) => 'v = "";

  [@bs.send] external preload: (resource('i, 'v), 'i) => unit = "";
};

type api_input = {
  token: option(string),
  user: string,
};

type state =
  | Data(Feed.t)
  | Error(string);

let feedResource =
  ReactCache.createResourceWithCustomHash(
    ({token, user}) =>
      getFeed(~token?, user)
      |> Utils.Promise.map(
           fun
           | Result.Ok(feed) => Data(feed)
           | Error(e) =>
             Error(Format.asprintf("%a", Decoders_bs.Decode.pp_error, e)),
         ),
    ({token, user}) =>
      switch (token) {
      | Some(token) => `String(user ++ token)
      | None => `String(user)
      },
  );
