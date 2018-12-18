import ApplicationController from '../application_controller';

export default class extends ApplicationController {
  static targets = ['output'];

  onSuccess(event) {
    const [data, status, xhr] = event.detail;
    super.log(data);
    if (status === 'OK') {
      this.outputTarget.innerHTML = xhr.response;
    }
  }
}
