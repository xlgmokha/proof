import { Controller } from 'stimulus'

export default class extends Controller {
  validate() {
    if (this.password && this.email) {
      console.log("valid")
    } else {
      console.log("invalid")
    }
  }

  get email() {
    return this.targets.find("email").value
  }

  get password() {
    return this.targets.find("password").value
  }
}
