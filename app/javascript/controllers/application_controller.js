// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction

import { Controller } from 'stimulus';

export default class extends Controller {
  get isDevelopment() {
    return process.env.RAILS_ENV === 'development';
  }

  initialize() {
    this.log(`Loading... ${this.identifier}`);
  }

  connect() {
    this.log(`Connected to ${this.element.outerHTML} to ${this.identifier}`);
  }

  disconnect() {
    this.log(`Disconnected from ${this.identifier}`);
  }

  enable(element) {
    element.removeAttribute('disabled');
  }

  disable(element) {
    element.setAttribute('disabled', 'disabled');
  }

  hide(element) {
    if (element)
      element.classList.add('hide');
  }

  show(element) {
    if (element)
      element.classList.remove('hide');
  }

  log(message) {
    if (this.isDevelopment) {
      console.log(message); /* eslint-disable-line no-console */
    }
  }

  controllerFor(element, identifier) {
    return this.application.getControllerForElementAndIdentifier(element, identifier);
  }
}
