import { Controller } from "@hotwired/stimulus"

// Copies the source target's text and briefly confirms on the button.
export default class extends Controller {
  static targets = [ "source", "button" ]
  static values = { copiedLabel: String }

  async copy() {
    const text = this.sourceTarget.value ?? this.sourceTarget.textContent
    await navigator.clipboard.writeText(text.trim())

    const label = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedLabelValue
    setTimeout(() => { this.buttonTarget.textContent = label }, 2000)
  }
}
