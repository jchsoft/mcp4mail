import { Controller } from "@hotwired/stimulus"

// Plays the hero's chat mock: the question is typed into the composer and sent,
// the AI's tool calls tick off one by one, then the answer builds up bullet by
// bullet. The server renders the finished conversation, which is what a visitor
// without JavaScript (or who asked the OS for less motion) keeps; connecting is
// what rewinds it to an empty chat. Every hidden piece only loses its opacity,
// never its box, so the figure holds its final height throughout.
//
// The first run waits until the figure scrolls into view; a replay waits for
// the hold to pass with the figure in view and the tab visible.
export default class extends Controller {
  static targets = [ "composer", "send", "question", "questionText", "working", "step", "spinner", "check", "answer", "source", "item" ]

  static TYPE_MS = 35
  static STEP_MS = 750
  static HOLD_MS = 6000

  connect() {
    this.placeholder = this.composerTarget.textContent
    this.run = 0
    this.sync = this.sync.bind(this)
    this.resume = this.resume.bind(this)
    this.motion = matchMedia("(prefers-reduced-motion: reduce)")
    this.motion.addEventListener("change", this.sync)
    this.sync()
  }

  disconnect() {
    this.motion.removeEventListener("change", this.sync)
    this.stop()
  }

  // The visitor can ask the OS for less motion while the page is open: the mock
  // then jumps to the finished conversation and stays there, and asking for
  // motion again starts it from the top the next time it is in view.
  sync() {
    if (this.motion.matches) this.stop()
    else this.start()
  }

  start() {
    if (this.observer) return

    this.due = true
    this.revealed.forEach(element => element.classList.add("hero-demo-reveal"))
    this.rewind()

    this.observer = new IntersectionObserver(([ entry ]) => {
      this.inView = entry.isIntersecting
      this.resume()
    })
    this.observer.observe(this.element)
    document.addEventListener("visibilitychange", this.resume)
  }

  stop() {
    if (!this.observer) return

    this.observer.disconnect()
    this.observer = null
    document.removeEventListener("visibilitychange", this.resume)
    this.run++
    clearTimeout(this.timer)
    this.finish()
  }

  resume() {
    if (!this.due || !this.inView || document.hidden) return

    this.due = false
    this.play()
  }

  async play() {
    const run = ++this.run
    this.rewind()

    for (const [ delay, action ] of this.script) {
      await this.wait(delay)
      if (run !== this.run) return
      action()
    }

    await this.wait(this.constructor.HOLD_MS)
    if (run !== this.run) return
    this.due = true
    this.resume()
  }

  // [delay before, action] pairs, one per beat of the sequence.
  get script() {
    const { TYPE_MS, STEP_MS } = this.constructor
    const question = this.questionTextTarget.textContent.trim()

    return [
      [ 400, () => this.type("") ],
      ...[ ...question ].map((_, i) => [ TYPE_MS, () => this.type(question.slice(0, i + 1)) ]),
      [ 300, () => this.pulse(this.sendTarget) ],
      [ 250, () => this.sent() ],
      [ 500, () => this.show(this.workingTarget) ],
      ...this.stepTargets.flatMap((step, i) => [
        [ i === 0 ? 0 : 100, () => this.start(i) ],
        [ STEP_MS, () => this.complete(i) ]
      ]),
      [ 400, () => this.show(this.answerTarget) ],
      [ 300, () => this.show(this.sourceTarget) ],
      ...this.itemTargets.map(item => [ 450, () => this.show(item) ])
    ]
  }

  type(text) {
    this.composerTarget.textContent = text
    this.composerTarget.classList.add("hero-demo-caret")
    this.composerTarget.scrollLeft = this.composerTarget.scrollWidth
  }

  sent() {
    this.resetComposer()
    this.show(this.questionTarget)
  }

  start(index) {
    this.spinnerTargets[index].classList.remove("hidden")
    this.checkTargets[index].classList.add("hidden")
    this.show(this.stepTargets[index])
  }

  complete(index) {
    this.spinnerTargets[index].classList.add("hidden")
    this.checkTargets[index].classList.remove("hidden")
  }

  pulse(element) {
    element.classList.remove("hero-demo-pulse")
    void element.offsetWidth
    element.classList.add("hero-demo-pulse")
  }

  show(element) {
    element.classList.remove("hero-demo-pending")
  }

  rewind() {
    this.resetComposer()
    this.revealed.forEach(element => element.classList.add("hero-demo-pending"))
  }

  finish() {
    this.resetComposer()
    this.revealed.forEach(element => element.classList.remove("hero-demo-pending", "hero-demo-reveal"))
    this.stepTargets.forEach((_, i) => this.complete(i))
  }

  resetComposer() {
    this.composerTarget.textContent = this.placeholder
    this.composerTarget.classList.remove("hero-demo-caret")
    this.composerTarget.scrollLeft = 0
  }

  wait(ms) {
    return new Promise(resolve => this.timer = setTimeout(resolve, ms))
  }

  get revealed() {
    return [ this.questionTarget, this.workingTarget, ...this.stepTargets, this.answerTarget, this.sourceTarget, ...this.itemTargets ]
  }
}
