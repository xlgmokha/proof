import ApplicationController from './application_controller';

export default class extends ApplicationController {
  close() {
    this.element.remove();
  }
}
