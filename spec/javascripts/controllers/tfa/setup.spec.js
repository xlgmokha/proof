import Controller from '../../../../app/javascript/controllers/tfa/setup_controller'
import { Application } from 'stimulus';

describe('tfa--setup', () => {
  beforeEach(() => {
    const $container = affix('div[data-controller="tfa--setup"]')
    $container.affix('canvas[data-target="tfa--setup.canvas"]')
    const $form = $container.affix('form')
    $form.affix('input[type="hidden" data-target="tfa--setup.secret" value="secret"]')
    const application = Application.start();
    application.register('tfa--setup', Controller);
  });

  describe("connect", () => {
    it("displays a QR code representation of the secret", () => {
      expect($('canvas')).toBeDefined()
    });
  });
});
