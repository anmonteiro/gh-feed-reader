open Belt;

[@bs.module] external css: Js.t({..}) as 'a = "./App.module.scss";

let parseFeed = payload =>
  Decoders_bs.Decode.decode_value(Decode_feed.decode_feed, payload);

let getFeed = (~token=?, user) => {
  let endpoint = {j|https://gh-feed.anmonteiro.now.sh/api?user=$(user)|j};
  let endpoint =
    switch (token) {
    | None => endpoint
    | Some(token) => {j|$(endpoint)&token=$(token)|j}
    };
  Request.request_json(endpoint)
  |> Js.Promise.(then_(payload => resolve(parseFeed(payload))));
};

module Entry = {
  module Entry = Feed.Entry;

  [@react.component]
  let make = (~entry) => {
    let date = {
      let dateMs =
        switch (entry.Entry.published) {
        | Some(published) => published
        | None => entry.updated
        };
      let jsDate = Js.Date.fromFloat(dateMs);
      Utils.formatDate(jsDate);
    };
    let dateCaption = "On " ++ date ++ ":";
    <article>
      <Ui.Card>
        <div className=css##entryDate>
          {switch (entry.links) {
           | [] => React.string(dateCaption)
           | [{Feed.Link.title, href}, ..._] =>
             <a title href> {React.string(dateCaption)} </a>
           }}
        </div>
        {switch (entry.content) {
         | Some(content) =>
           <div
             className=css##entryContent
             dangerouslySetInnerHTML={"__html": content}
           />
         | None => React.null
         }}
      </Ui.Card>
    </article>;
  };
};

module GithubFeed = {
  type state =
    | Loading
    | Data(Feed.t)
    | Error(string);

  let feedTitle = (~link=?, feedTitle) => {
    switch (link) {
    | Some({Feed.Link.title, href}) =>
      <a className=css##feedTitle title href> {React.string(feedTitle)} </a>
    | None =>
      <span className=css##feedTitle> {React.string(feedTitle)} </span>
    };
  };

  [@react.component]
  let make = () => {
    open Utils;
    let {ReasonReactRouter.search} = ReasonReactRouter.useUrl();
    let qp = QueryParams.make(search);
    let ((user, token), _updateUser) =
      React.useState(() => {
        let user =
          switch (QueryParams.get(qp, "user")) {
          | Some(user) => user
          | None => "anmonteiro"
          };
        (user, QueryParams.get(qp, "token"));
      });
    let (state, updateState) = React.useState(() => Loading);
    React.useEffect0(() => {
      let _ =
        getFeed(~token?, user)
        |> Utils.Promise.map(
             fun
             | Result.Ok(feed) => updateState(_ => Data(feed))
             | Error(e) =>
               updateState(_ =>
                 Error(Format.asprintf("%a", Decoders_bs.Decode.pp_error, e))
               ),
           );
      None;
    });

    <div>
      <header className=css##appHeader>
        <h2>
          {switch (state) {
           | Data({Feed.links, title}) =>
             switch (links) {
             | [link, ..._] => feedTitle(~link, title)
             | _ => feedTitle(title)
             }
           | Loading => React.string("Feed")
           | Error(_) => React.string("Error")
           }}
        </h2>
      </header>
      <main className=css##appMain>
        <section>
          {switch (state) {
           | Loading => React.null
           | Data(feed) =>
             feed.Feed.entries
             ->List.mapWithIndex((i, entry) =>
                 <Entry key={string_of_int(i)} entry />
               )
             ->List.toArray
             ->React.array
           | Error(_) => React.null
           }}
        </section>
      </main>
    </div>;
  };
};

/* TODO: insert a username to fetch */
[@react.component]
let make = () => <GithubFeed />;
