import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "input"]
  static values = { url: String }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-primary", "bg-primary/5")
  }

  dragenter(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-primary", "bg-primary/5")
  }

  dragleave(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-primary", "bg-primary/5")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-primary", "bg-primary/5")
    this.uploadFiles(event.dataTransfer.files)
  }

  click() {
    this.inputTarget.click()
  }

  change(event) {
    this.uploadFiles(event.target.files)
    event.target.value = ""
  }

  async uploadFiles(files) {
    for (const file of files) {
      await this.uploadFile(file)
    }
  }

  async uploadFile(file) {
    const name = this.extractPolicyName(file.name)
    const formData = new FormData()
    formData.append("onboarding_policy[name]", name)
    formData.append("onboarding_policy[document]", file)

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: formData
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }

  extractPolicyName(filename) {
    // Remove file extension and clean up the name
    return filename
      .replace(/\.(pdf|doc|docx)$/i, "")
      .replace(/[-_]/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  }
}
