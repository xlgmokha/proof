import ApplicationController from '../application_controller';

export default class extends ApplicationController {
  static targets = ["output"];

  onSuccess(event) {
    let [data, status, xhr] = event.detail;
    this.outputTarget.innerHTML = xhr.response;
  }
}
