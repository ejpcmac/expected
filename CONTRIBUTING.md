# Contributing to Expected

This project uses [git-flow](https://github.com/petervanderdoes/gitflow-avh).
The `master` branch is reserved to releases: the development process occurs on
`develop` and feature branches. **Please never commit to master.**

## Setup

### Local repository

1. Fork the repository

2. Clone your fork to a local repository:

        $ git clone https://github.com/you/expected.git
        $ cd expected

3. Add the main repository as a remote:

        $ git remote add upstream https://github.com/jpc/expected.git

4. Checkout to `develop`:

        $ git checkout develop

### Development environment

1. Install an Elixir environment.

2. Fetch the project dependencies and build the project:

        $ mix do deps.get, compile

3. Launch the tests:

        $ mix test --stale

All tests should pass.

## Workflow

To make a change, please follow this workflow:

1. Checkout to `develop` and apply the last upstream changes (use rebase, not
    merge!):

        $ git checkout develop
        $ git fetch --all --prune
        $ git rebase upstream/develop

2. Create a new branch with an explicit name:

        $ git checkout -b <my_branch>

3. Work on your feature (don’t forget to write some tests, TDD is good ;-)):

        # Some work
        $ git commit -am "My first change"
        # Some work
        $ git commit -am "My second change"
        ...

4. When your feature is ready, feel free to use
    [interactive rebase](https://help.github.com/articles/about-git-rebase/) so
    your history looks clean and is easy to follow. Then, apply the last
    upstream changes on `develop` to prepare integration:

        $ git checkout develop
        $ git fetch --all --prune
        $ git rebase upstream/develop

5. If there were commits on `develop` since the beginning of your feature
    branch, integrate them by **rebasing**:

        $ git checkout <my_feature_branch>
        $ git rebase develop

6. Run the tests and static analyzers to ensure there is no regression and all
    works as expected:

        $ mix test
        $ mix dialyzer
        $ mix credo

7. If it’s all good, open a pull request to merge your branch into the `develop`
    branch on the main repository.
