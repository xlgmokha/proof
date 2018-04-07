import SessionsController from '../../../app/javascript/controllers/sessions_controller'

describe('SessionsController', () => {
  let subject = null;

  beforeEach(() => {
    subject = new SessionsController();
  });

  it("is alive", () => {
    expect(subject).toEqual(jasmine.any(SessionsController));
  });

  describe("validate", () => {
    xit("disables the submit button when the email is blank", () => {
      subject.validate();
    });
  });
});
