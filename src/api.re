let parseFeed = payload =>
  switch (Decoders_bs.Decode.decode_value(Decode_feed.decode_feed, payload)) {
  | Ok(data) => Ok(data)
  | Error(e) => Error(Format.asprintf("%a", Decoders_bs.Decode.pp_error, e))
  };

let getFeed = (~token=?, ~page, user) => {
  let endpoint = {j|https://gh-feed.now.sh/api?user=$(user)&page=$(page)|j};
  let endpoint =
    switch (token) {
    | None => endpoint
    | Some(token) => {j|$(endpoint)&token=$(token)|j}
    };
  Request.request_json(endpoint)
  ->Promise.map(
      fun
      | Ok(json) => parseFeed(json)
      | Error(s) => Error(s),
    );
};

module ReactCache = {
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

  [@bs.send] external read: (resource('i, 'v), 'i) => 'v = "read";

  [@bs.send] external preload: (resource('i, 'v), 'i) => unit = "preload";
};

type api_input = {
  token: option(string),
  user: string,
  page: int,
};

type state =
  | Data(Feed.t)
  | Error(string);

let feedResource =
  ReactCache.createResourceWithCustomHash(
    ({token, user, page}) =>
      getFeed(~token?, ~page, user)
      ->Promise.map(
          fun
          | Ok(feed) => Data(feed)
          | Error(e) => Error(e),
        )
      ->Promise.Js.toBsPromise,
    ({token, user, page}) => {
      let hash = user ++ string_of_int(page);
      switch (token) {
      | Some(token) => `String(hash ++ token)
      | None => `String(hash)
      };
    },
  );
