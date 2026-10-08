module.exports = (api) => {
  api.cache(true);
  return {
    presets: [[require.resolve('shakapacker/package/babel/preset.js')]],
  };
};
