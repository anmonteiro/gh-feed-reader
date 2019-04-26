open Belt;

[@bs.module] external css: Js.t({..}) as 'a = "./App.module.scss";

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

module Header = {
  let feedTitle = (~link=?, feedTitle) => {
    switch (link) {
    | Some({Feed.Link.title, href}) =>
      <a className=css##feedTitle title href> {React.string(feedTitle)} </a>
    | None =>
      <span className=css##feedTitle> {React.string(feedTitle)} </span>
    };
  };

  [@react.component]
  let make = (~link=?, ~title) => {
    <header className=css##appHeader>
      <h2> {feedTitle(~link?, title)} </h2>
    </header>;
  };
};

module GithubFeed = {
  [@react.component]
  let make = (~token=?, ~user) => {
    let state = Api.ReactCache.read(Api.feedResource, {user, token});
    let (link, title) =
      switch (state) {
      | Data({Feed.links, title}) =>
        switch (links) {
        | [link, ..._] => (Some(link), title)
        | _ => (None, title)
        }
      | Error(msg) => (None, Format.asprintf("Error: %s", msg))
      };

    <>
      <Header ?link title />
      <main className=css##appMain>
        <section>
          {switch (state) {
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
    </>;
  };
};

/* TODO: insert a username to fetch */
[@react.component]
let make = () => {
  open Utils;
  let {ReasonReactRouter.search, path} = ReasonReactRouter.useUrl();
  let qp = QueryParams.make(search);
  let ((user, token), _updateUser) =
    React.useState(() => {
      let user =
        switch (path) {
        | [user, ..._] => user
        | _ => "anmonteiro"
        };
      (user, QueryParams.get(qp, "token"));
    });
  <div>
    <React.Suspense maxDuration=250 fallback={<Header title="Loading" />}>
      <GithubFeed ?token user />
    </React.Suspense>
  </div>;
};
