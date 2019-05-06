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

module FeedPage = {
  [@react.component]
  let make = (~token=?, ~page, ~user, ~loadingRef) => {
    let feedPage =
      Api.ReactCache.read(Api.feedResource, {user, token, page});

    /* If this is executed, it means the data was successfully read from the
     * remote endpoint. We are done loading. */
    React.useEffect0(() => {
      React.Ref.setCurrent(loadingRef, false);
      None;
    });

    <section>
      {switch (feedPage) {
       | Data({Feed.entries}) =>
         entries
         ->List.reduceWithIndexU(
             Array.makeUninitializedUnsafe(List.length(entries)),
             (. arr, entry, i) => {
               Array.setUnsafe(
                 arr,
                 i,
                 <Entry key={string_of_int(i)} entry />,
               );
               arr;
             },
           )
         ->React.array
       | Error(_) => React.null
       }}
    </section>;
  };
};

module GithubFeed = {
  [@react.component]
  let make = (~token=?, ~user, ~page, ~loadingRef) => {
    /* first page is always shown, and we need it to show the header */
    let firstPage =
      Api.ReactCache.read(Api.feedResource, {user, token, page: 1});
    let (link, title) =
      switch (firstPage) {
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
        {React.array(
           Array.makeByU(page, (. i) =>
             <React.Suspense key=i fallback={<div className=css##loader />}>
               <FeedPage ?token page={i + 1} user loadingRef />
             </React.Suspense>
           ),
         )}
      </main>
    </>;
  };
};

/* TODO: insert a username to fetch */
[@react.component]
let make = () => {
  open Utils;
  let {ReasonReactRouter.search, path} = ReasonReactRouter.useUrl();
  let (page, setPage) = React.useState(() => 1);
  let {Scroll.y, _} = Scroll.useScroll();
  let loadingRef = React.useRef(false);

  React.useEffect3(
    () => {
      let loading = React.Ref.current(loadingRef);
      if (!loading) {
        let totalHeight = window##innerHeight + y;
        let offsetHeight = documentElement##offsetHeight;
        /* allow a 20px epsilon */
        if (totalHeight === offsetHeight) {
          React.Ref.setCurrent(loadingRef, true);
          setPage(prev => prev + 1);
        };
      };
      None;
    },
    (page, setPage, y),
  );

  let qp = QueryParams.make(search);
  let (user, token) = {
    let user =
      switch (path) {
      | [user, ..._] => user
      | _ => "anmonteiro"
      };
    (user, QueryParams.get(qp, "token"));
  };

  <div>
    <React.Suspense fallback={<Header title="Loading" />}>
      <GithubFeed ?token page user loadingRef />
    </React.Suspense>
  </div>;
};
