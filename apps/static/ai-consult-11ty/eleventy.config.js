/** @param {import("@11ty/eleventy").UserConfig} eleventyConfig */
module.exports = function (eleventyConfig) {
  eleventyConfig.addGlobalData("buildYear", new Date().getFullYear());
  eleventyConfig.addGlobalData("siteTitle", "KI-Beratung");
  eleventyConfig.addPassthroughCopy("src/css");
  eleventyConfig.addPassthroughCopy("src/img");

  return {
    dir: {
      input: "src",
      includes: "_includes",
      output: "_site",
    },
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk",
  };
};
