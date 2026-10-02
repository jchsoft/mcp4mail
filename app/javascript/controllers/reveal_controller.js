import { Controller } from "@hotwired/stimulus"

// Shows its content targets while a checkbox is ticked, at once, without waiting for the server.
export default class extends Controller {
  static targets = [ "content" ]

  toggle({ target }) {
    this.contentTargets.forEach((content) => content.classList.toggle("hidden", !target.checked))
  }
}
