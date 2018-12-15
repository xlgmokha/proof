import ApplicationController from './application_controller';

export default class extends ApplicationController {
  connect() {
    this.load();

    if (this.data.has('refreshInterval')) {
      this.startRefreshing();
    }
  }

  disconnect() {
    this.stopRefreshing();
  }

  load() {
    fetch(this.data.get('url'))
      .then(response => response.text())
      .then((html) => {
        this.element.innerHTML = html;
      });
  }

  startRefreshing() {
    this.refreshTimer = setInterval(() => {
      this.load();
    }, this.data.get('refreshInterval'));
  }

  stopRefreshing() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
    }
  }
}
