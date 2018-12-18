import ApplicationController from './application_controller';

export default class extends ApplicationController {
  static targets = ['source'];

  connect() {
    if (document.queryCommandSupported('copy')) {
      this.element.classList.add('clipboard--supported');
    }
  }

  copy(event) {
    event.preventDefault();
    this.sourceTarget.select();
    document.execCommand('copy');
  }
}
