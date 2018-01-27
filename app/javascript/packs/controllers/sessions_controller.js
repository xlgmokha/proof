import { Controller } from 'stimulus'
import Email from '../models/email'

export default class extends Controller {
  get email() { return this.targets.find("email") }
  get password() { return this.targets.find("password") }
  get submitButton() { return this.targets.find("submit") }

  validate() {
    if (this.isValidEmail() && this.isValidPassword()) {
      this.enable(this.submitButton);
    } else {
      this.disable(this.submitButton)
    }
  }

  enable(element) {
    element.removeAttribute('disabled');
  }

  disable(element) {
    element.setAttribute('disabled', 'disabled');
  }

  isPresent(element) {
    return element.value.length > 0;
  }

  isValidEmail() {
    return new Email(this.email.value).valid();
  }

  isValidPassword() {
    return this.isPresent(this.password);
  }
}
