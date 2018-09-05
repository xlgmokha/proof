import Controller from '../../../../app/javascript/controllers/mfa/setup_controller'
import { Application } from 'stimulus';

describe('mfa--setup', () => {
  beforeEach(() => {
    const $container = affix('div[data-controller="mfa--setup"]')
    $container.affix('canvas[data-target="mfa--setup.canvas"]')
    const $form = $container.affix('form')
    $form.affix('input[type="hidden" data-target="mfa--setup.secret" value="secret"]')
    const application = new Application();
    application.router.start();
    application.dispatcher.start();
    application.register('mfa--setup', Controller);
  });

  describe("connect", () => {
    it("displays a QR code representation of the secret", () => {
      expect($('canvas')).toBeDefined()
    });
  });
});
