import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a control changes, for settings that save themselves.
// The redirect back replaces the page, so focus would fall to <body> and a keyboard
// user would start again from the top: the control that changed takes focus back.
export default class extends Controller {
  submit({ target }) {
    if (target.id) {
      document.addEventListener("turbo:load", () => document.getElementById(target.id)?.focus({ preventScroll: true }), { once: true })
    }
    this.element.requestSubmit()
  }
}
