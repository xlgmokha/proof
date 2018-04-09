import SessionsController from '../../../app/javascript/controllers/sessions_controller'
import { Application } from 'stimulus';

describe('SessionsController', () => {
  beforeEach(() => {
    let $form = affix('form[data-controller="sessions"]')
    $form.affix('input[data-target="sessions.email" data-action="keyup->sessions#validate" type="email" id="user_email"]')
    $form.affix('input[data-target="sessions.password" data-action="keyup->sessions#validate" type="password" id="user_password"]')
    $form.affix('button[name="button" type="submit" data-target="sessions.submit"]')
    const stimulusApp = Application.start();
    stimulusApp.register('sessions', SessionsController);
  });

  describe("validate", () => {
    it("disables the submit button when the email is blank", () => {
      $('#user_email').val('')
      document.getElementById('user_email').dispatchEvent(new Event('keyup'))
      expect($('button[type="submit"]').attr('disabled')).toBe('disabled')
    });

    it("disables the submit button when the password is blank", () => {
      $('#user_password').val('');
      document.getElementById('user_password').dispatchEvent(new Event('keyup'))
      expect($('button[type="submit"]').attr('disabled')).toBe('disabled')
    });

    it ("enables the submit button when all fields are provided", () => {
      $('#user_email').val('email@example.com');
      $('#user_password').val('password');
      document.getElementById('user_password').dispatchEvent(new Event('keyup'))
      expect($('button[type="submit"]').attr('disabled')).toBe(undefined)
    });
  });
});
