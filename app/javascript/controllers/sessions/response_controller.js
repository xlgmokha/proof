import ApplicationController from '../application_controller';

export default class extends ApplicationController {
  connect() {
    setTimeout(() => {
      this.element.submit();
    }, 5000);
  }
}
