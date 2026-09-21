import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a control changes, for settings that save themselves.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
