// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

window.addEventListener("phx:js_set_attribute", ({detail}) => {
  document.querySelectorAll(detail.selector).forEach(element => {
    Object.entries(detail.attributes).forEach(([attribute_name, value]) => {
      element.setAttribute(attribute_name, value);
    })
  })
})

window.addEventListener("phx:js_hide", ({detail}) => {
  // Transition classes are from `&CloudDbUiWeb.CoreComponents.hide/2`.
  document.querySelectorAll(detail.selector).forEach(element => {
    const classOld = element.className;
    const classTransition = "transition-all transform ease-in duration-200";

    element.className = classOld + " " + classTransition + 
                        " opacity-100 translate-y-0 sm:scale-100";
    element.className = classOld + " " + classTransition + 
                        " opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95";

    setTimeout(() => {
      element.setAttribute("style", "display: none;");
      element.className = classOld;
    }, detail.time)
  })
})

window.addEventListener("phx:js_set_text", ({detail}) => {
  document.querySelectorAll(detail.selector).forEach(element => {
    element.textContent = detail.text
  })
})