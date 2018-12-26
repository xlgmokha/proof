import Controller from '../../../../app/javascript/controllers/mfa/setup_controller'
import { Application } from 'stimulus';

describe('mfa--setup', () => {
  beforeEach(() => {
    fixture.setBase('spec/fixtures')
    const el = fixture.load('mfa-setup.html')

    const application = new Application();
    application.router.start();
    application.dispatcher.start();
    application.register('mfa--setup', Controller);
  });

  afterEach(() => {
    fixture.cleanup();
  });

  describe("connect", () => {
    it("displays a QR code representation of the secret", () => {
      expect($('canvas')).toBeDefined()
    });
  });
});
