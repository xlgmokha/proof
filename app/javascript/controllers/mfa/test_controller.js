import ApplicationController from '../application_controller';

export default class extends ApplicationController {
  static targets = ["message"];

  onResponse(event) {
    let [data, status, xhr] = event.detail;
    this.messageTarget.innerHTML = xhr.response;
  }
}
