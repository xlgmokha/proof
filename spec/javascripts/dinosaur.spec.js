import Dinosaur from '../../app/javascript/models/dinosaur'

describe("Dinosaur", () => {
  it("Dinosaurs are extinct", () => {
    expect((new Dinosaur).isExtinct).toBeTruthy();
  });
});
