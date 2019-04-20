[@bs.module] external css: Js.t({..}) as 'a = "./Ui.module.scss";

module Card = {
  [@react.component]
  let make = (~children) => {
    <div className=css##card>
      <div className=css##cardInner> children </div>
    </div>;
  };
};
