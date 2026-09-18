import { Controller } from "@hotwired/stimulus"

// Turns a stack of headed panels into a segmented control. The markup ships with
// every panel open and the tablist hidden, so a visitor without JavaScript reads
// all of them; connecting is what collapses the stack down to one.
export default class extends Controller {
  static targets = [ "tablist", "tab", "panel", "heading" ]

  connect() {
    this.tablistTarget.hidden = false
    this.headingTargets.forEach(heading => heading.hidden = true)
    this.show(0)
  }

  select(event) {
    this.show(this.tabTargets.indexOf(event.currentTarget))
  }

  navigate(event) {
    const current = this.tabTargets.indexOf(event.currentTarget)
    const last = this.tabTargets.length - 1
    const moves = {
      ArrowRight: current === last ? 0 : current + 1,
      ArrowLeft: current === 0 ? last : current - 1,
      Home: 0,
      End: last
    }

    if (!(event.key in moves)) return

    event.preventDefault()
    this.show(moves[event.key])
    this.tabTargets[moves[event.key]].focus()
  }

  show(index) {
    this.tabTargets.forEach((tab, i) => {
      tab.setAttribute("aria-selected", i === index)
      tab.tabIndex = i === index ? 0 : -1
    })
    this.panelTargets.forEach((panel, i) => panel.hidden = i !== index)
  }
}
