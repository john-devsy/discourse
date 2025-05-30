import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import PollResultsStandard from "discourse/plugins/poll/discourse/components/poll-results-standard";

const TWO_OPTIONS = [
  { id: "1ddc47be0d2315b9711ee8526ca9d83f", html: "This", votes: 5, rank: 0 },
  { id: "70e743697dac09483d7b824eaadb91e1", html: "That", votes: 4, rank: 0 },
];

const TWO_OPTIONS_REVERSED = [
  { id: "1ddc47be0d2315b9711ee8526ca9d83f", html: "This", votes: 4, rank: 0 },
  { id: "70e743697dac09483d7b824eaadb91e1", html: "That", votes: 5, rank: 0 },
];

const FIVE_OPTIONS = [
  { id: "1ddc47be0d2315b9711ee8526ca9d83f", html: "a", votes: 5, rank: 0 },
  { id: "70e743697dac09483d7b824eaadb91e1", html: "b", votes: 2, rank: 0 },
  { id: "6c986ebcde3d5822a6e91a695c388094", html: "c", votes: 4, rank: 0 },
  { id: "3e4a8f7e5f9d02f2bd7aebdb345c6ec2", html: "b", votes: 1, rank: 0 },
  { id: "a5e3e8c77ac2b1f43dd98ee6ff9d34e3", html: "a", votes: 1, rank: 0 },
];

const PRELOADEDVOTERS = {
  db753fe0bc4e72869ac1ad8765341764: [
    {
      id: 1,
      username: "bianca",
      name: null,
      avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
    },
  ],
};

module("Poll | Component | poll-results-standard", function (hooks) {
  setupRenderingTest(hooks);

  test("Renders the standard results Component correctly", async function (assert) {
    const self = this;

    this.setProperties({
      options: TWO_OPTIONS,
      pollName: "Two Choice Poll",
      pollType: "single",
      isPublic: true,
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 9,
      fetchVoters: () => {},
    });

    await render(
      <template>
        <PollResultsStandard
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @isPublic={{self.isPublic}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
        />
      </template>
    );

    assert.dom(queryAll(".option .percentage")[0]).hasText("56%");
    assert.dom(queryAll(".option .percentage")[1]).hasText("44%");
    assert.dom("ul.poll-voters-list").exists();
  });

  test("Omits voters for private polls", async function (assert) {
    const self = this;

    this.setProperties({
      options: TWO_OPTIONS,
      pollName: "Two Choice Poll",
      pollType: "single",
      isPublic: false,
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 9,
      fetchVoters: () => {},
    });

    await render(
      <template>
        <PollResultsStandard
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @isPublic={{self.isPublic}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
        />
      </template>
    );

    assert.dom("ul.poll-voters-list").doesNotExist();
  });

  test("options in ascending order", async function (assert) {
    const self = this;

    this.setProperties({
      options: TWO_OPTIONS_REVERSED,
      pollName: "Two Choice Poll",
      pollType: "single",
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 9,
      fetchVoters: () => {},
    });

    await render(
      <template>
        <PollResultsStandard
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
        />
      </template>
    );

    assert.dom(queryAll(".option .percentage")[0]).hasText("56%");
    assert.dom(queryAll(".option .percentage")[1]).hasText("44%");
  });

  test("options in ascending order", async function (assert) {
    const self = this;

    this.setProperties({
      options: FIVE_OPTIONS,
      pollName: "Five Multi Option Poll",
      pollType: "multiple",
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 12,
      fetchVoters: () => {},
    });

    await render(
      <template>
        <PollResultsStandard
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
        />
      </template>
    );

    let percentages = queryAll(".option .percentage");
    assert.dom(percentages[0]).hasText("41%");
    assert.dom(percentages[1]).hasText("33%");
    assert.dom(percentages[2]).hasText("16%");
    assert.dom(percentages[3]).hasText("8%");

    assert.dom(queryAll(".option")[3].querySelectorAll("span")[1]).hasText("a");
    assert.dom(percentages[4]).hasText("8%");
    assert.dom(queryAll(".option")[4].querySelectorAll("span")[1]).hasText("b");
  });

  test("options in ascending order, showing absolute vote number", async function (assert) {
    const self = this;

    this.setProperties({
      options: FIVE_OPTIONS,
      pollName: "Five Multi Option Poll",
      pollType: "multiple",
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 12,
      fetchVoters: () => {},
      showTally: true,
    });

    await render(
      <template>
        <PollResultsStandard
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
          @showTally={{self.showTally}}
        />
      </template>
    );

    let percentages = queryAll(".option .absolute");
    assert.dom(percentages[0]).hasText(i18n("poll.votes", { count: 5 }));
    assert.dom(percentages[1]).hasText(i18n("poll.votes", { count: 4 }));
    assert.dom(percentages[2]).hasText(i18n("poll.votes", { count: 2 }));
    assert.dom(percentages[3]).hasText(i18n("poll.votes", { count: 1 }));

    assert.dom(queryAll(".option")[3].querySelectorAll("span")[1]).hasText("a");
    assert.dom(percentages[4]).hasText(i18n("poll.votes", { count: 1 }));
    assert.dom(queryAll(".option")[4].querySelectorAll("span")[1]).hasText("b");
  });
});
