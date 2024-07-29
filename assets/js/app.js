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

function needs_plural_form(value) {return value != -1 && value != 1;}

let Hooks = {}

// If the element using this `phx-hook=` passes a character limit
// in `data-value=`, the label text will include this character limit
// along with the character count.
Hooks.CharacterCounter = {
  mounted() {
    this.el.addEventListener("input", e => {
      const label = document.querySelector(`#${this.el.id}-label`)
      const trimmedLength = this.el.value.trim().length

      if (trimmedLength == 0) {
        label.textContent = label.textContent.replace(
          /\s+\(?\d+(?:\/\S+)?\s+[a-z]+\)\s*$|,?\s+\(?\d+(?:\/\S+)?\s+[a-z]+/, 
          ""
        )
        return;
      }

      if (label.textContent.match(/\d+(?:\/\S+)?\s+characters?\)\s*$/)) {
        // Already has `"N/M characters)"`.
        label.textContent = label.textContent.replace(
          /\d+(?=(?:\/\S+)?\s+characters?\))/, 
          trimmedLength
        )

        if (typeof(this.el.dataset.value) === "undefined") {
          label.textContent = label.textContent.replace(
            /(?<=\scharacter)s?(?=\))/, 
            needs_plural_form(trimmedLength) ? "s" : ""
          )
        }
      }
      else {
        if (label.textContent.match(/\)\s*$/)) {
          // Ends with `")"`, replace this `")"` with `", "`.
          label.textContent = label.textContent.replace(/\)\s*$/, ", ")
        }
        else {
          label.textContent += " ("
        }

        label.textContent += trimmedLength;

        if (typeof(this.el.dataset.value) === "undefined") {
          const s = needs_plural_form(trimmedLength) ? "s" : "";

          label.textContent += " character" + s + ")"
        } else {
          const s = needs_plural_form(this.el.dataset.value) ? "s" : "";

          label.textContent += "/" + this.el.dataset.value + 
                              " character" + s + ")"
        }
      } 
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})

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
    element.textContent = detail.text;
  })
})

window.addEventListener("phx:js_set_value", ({detail}) => {
  document.querySelectorAll(detail.selector).forEach(element => {
    element.value = detail.value;
  })
})

window.addEventListener("phx:js_set_selection_range", ({detail}) => {
  document.querySelectorAll(detail.selector).forEach(element => {
    element.setSelectionRange(detail.start, detail.end);
  })
})
