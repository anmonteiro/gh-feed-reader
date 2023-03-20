[@bs.module] external _css: Js.t({..}) = "./index.scss";

[@bs.module "./serviceWorker"]
external register_service_worker: unit => unit = "register";
[@bs.module "./serviceWorker"]
external unregister_service_worker: unit => unit = "unregister";

module ReactDOM = {
  type root;

  [@bs.module "react-dom"]
  external createRoot: Dom.element => root = "createRoot";

  [@bs.send] external render: (root, React.element) => unit = "render";

  [@bs.val] [@bs.return nullable]
  external _getElementById: string => option(Dom.element) =
    "document.getElementById";
  [@bs.val]
  external _getElementsByClassName: string => array(Dom.element) =
    "document.getElementsByClassName";

  let renderToElementWithClassName = className =>
    switch (_getElementsByClassName(className)) {
    | [||] =>
      raise(
        Invalid_argument(
          "ReactDOMRe.Unstable.renderToElementWithClassName: no element of class "
          ++ className
          ++ " found in the HTML.",
        ),
      )
    | elements => createRoot(Array.unsafe_get(elements, 0))
    };

  let createRootWithId = id =>
    switch (_getElementById(id)) {
    | None =>
      raise(
        Invalid_argument(
          "ReactDOMRe.Unstable.createRootWithId: no element of id "
          ++ id
          ++ " found in the HTML.",
        ),
      )
    | Some(element) => createRoot(element)
    };
};

let start = () => {
  let root = ReactDOM.createRootWithId("root");
  ReactDOM.render(root, <App />);
};

start();

// If you want your app to work offline and load faster, you can change
// unregister_service_worker() to register_service_worker() below. Note this
// comes with some pitfalls. Learn more about service workers:
// https://bit.ly/CRA-PWA
unregister_service_worker();
