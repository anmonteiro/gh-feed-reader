%bs.raw
{|import './App.css'|};

/* The snippet below is what we'd like to have, but it doesn't seem to play
 * well with BuckleScript code generation, because we'd need the default
 * export.
 *
 * [@bs.module] external logo: string = "./logo.svg";
 */
let logo = [%bs.raw {|require('./logo.svg')|}];

[@react.component]
let make = () => {
  <div className="App">
    <header className="App-header">
      <img src=logo className="App-logo" alt="logo" />
      <p>
        {React.string("Edit ")}
        <code> {React.string("src/App.re")} </code>
        {React.string(" and save to reload.")}
      </p>
      <a
        className="App-link"
        href="https://reasonml.github.io/reason-react"
        target="_blank"
        rel="noopener noreferrer">
        {React.string("Learn Reason React")}
      </a>
    </header>
  </div>;
};
