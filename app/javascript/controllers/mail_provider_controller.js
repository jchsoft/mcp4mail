import { Controller } from "@hotwired/stimulus"

// Fills host, port and SSL from the chosen provider preset and shows its hint.
export default class extends Controller {
  static targets = [ "select", "host", "port", "ssl", "hint" ]

  apply() {
    const option = this.selectTarget.selectedOptions[0]
    if (!option || !option.value) {
      this.hintTarget.textContent = ""
      this.hintTarget.hidden = true
      return
    }

    this.hostTarget.value = option.dataset.host || ""
    this.portTarget.value = option.dataset.port
    this.sslTarget.checked = option.dataset.ssl === "true"
    this.hintTarget.textContent = option.dataset.hint
    this.hintTarget.hidden = false
    if (!this.hostTarget.value) this.hostTarget.focus()
  }
}
