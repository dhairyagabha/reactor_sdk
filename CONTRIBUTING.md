# Contributing

Thanks for helping improve ReactorSDK.

## Development setup

1. Install the project Ruby with your version manager of choice. The repository pins the primary development version in [`.ruby-version`](.ruby-version).
2. Install dependencies with `bundle install`.
3. Run the default quality gate with `bundle exec rake`.

## Project standards

- Add or update tests for every behavioral change.
- Keep the public API and README examples aligned.
- Prefer small, focused pull requests over broad mixed changes.
- Run `bundle exec rspec` and `bundle exec rubocop` before opening a pull request.

## Pull requests

1. Create a branch from `main`.
2. Make the smallest change that fully solves the problem.
3. Update documentation, changelog entries, and examples when behavior changes.
4. Include a short summary of the change and how you verified it.
