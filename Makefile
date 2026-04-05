SHELL :=/bin/bash -e -o pipefail
PWD   := $(shell pwd)

.DEFAULT_GOAL := all
.PHONY: all
all: ## build pipeline
all: generate format check test

.PHONY: ci
ci: ## CI build pipeline
ci: all

.PHONY: precommit
precommit: ## validate the branch before commit
precommit: all

.PHONY: help
help:
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


flutter-clean:
	@flutter clean

.PHONY: version
version: ## Check flutter version
	@flutter --version

.PHONY: doctor
doctor: ## Check flutter doctor
	@flutter doctor

.PHONY: format
format: ## Format the code
	@dart format -l 100 lib/ test/

.PHONY: fmt
fmt: format

.PHONY: fix
fix: format ## Fix the code
	@dart fix --apply lib

.PHONY: get
get: ## Get the dependencies
	@flutter pub get

.PHONY: upgrade
upgrade: get ## Upgrade dependencies
	@flutter pub upgrade

.PHONY: upgrade-major
upgrade-major: get ## Upgrade to major versions
	@flutter pub upgrade --major-versions

.PHONY: outdated
outdated: get ## Check for outdated dependencies
	@flutter pub outdated --show-all --dev-dependencies --dependency-overrides --transitive --no-prereleases

.PHONY: dependencies
dependencies: get ## Check outdated dependencies
	@flutter pub outdated --dependency-overrides \
		--dev-dependencies --prereleases --show-all --transitive

.PHONY: test
test: get ## Run the tests
	@flutter test --coverage test/unit_test.dart test/widget_test.dart

.PHONY: integration
integration: get ## Run the integration tests
	@flutter test \
		--coverage \
		integration_test/app_test.dart

.PHONY: e2e
e2e: integration

#.PHONY: publish-check
#publish-check: ## Check the package before publishing
#	@dart pub publish --dry-run

#.PHONY: publish
#publish: generate ## Publish the package
#	@yes | dart pub publish

# https://stackoverflow.com/questions/50789578/how-can-the-code-coverage-data-from-flutter-tests-be-displayed
.PHONY: coverage
coverage: get ## Generate the coverage report
	@dart pub global activate coverage
	@dart pub global run coverage:test_with_coverage -fb -o coverage -- \
		--platform vm --compiler=kernel --coverage=coverage \
		--reporter=expanded --file-reporter=json:coverage/tests.json \
		--timeout=10m --concurrency=12 --color \
			test/unit_test.dart test/smoke_test.dart
#	@dart test --concurrency=6 --platform vm --coverage=coverage test/
#	@dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
	@mv coverage/lcov.info coverage/lcov.base.info
	@lcov -r coverage/lcov.base.info -o coverage/lcov.base.info "lib/src/common/model/pb/schema.*.dart" "lib/**/*.g.dart"
	@mv coverage/lcov.base.info coverage/lcov.info
	@lcov --list coverage/lcov.info
	@genhtml -o coverage coverage/lcov.info

.PHONY: analyze
analyze: get ## Analyze the code
	@dart format --set-exit-if-changed -l 100 -o none lib/ test/
	@flutter analyze --fatal-infos --fatal-warnings lib/ test/

.PHONY: check
check: analyze publish-check ## Check the code
#	@dart pub global activate pana
#	@pana --json --no-warning --line-length 120 > log.pana.json

#.PHONY: pana
#pana: check

.PHONY: l10n
l10n: ## Generate localization
	@dart pub global activate intl_utils
	@dart pub global run intl_utils:generate
	@flutter gen-l10n --arb-dir lib/src/common/localization --output-dir lib/src/common/localization/generated --template-arb-file intl_en.arb

.PHONY: fluttergen
fluttergen: ## Generate assets
	@dart pub global activate flutter_gen
	@fluttergen -c pubspec.yaml

.PHONY: protobuf
protobuf: ## Generate protobuf
	@dart pub global activate protoc_plugin
	@protoc --proto_path=lib/src/common/model/pb --dart_out=lib/src/common/model/pb lib/src/common/model/pb/schema.proto

.PHONY: generate
generate: get l10n format fluttergen ## Generate the code
	@dart run build_runner build --delete-conflicting-outputs --release

.PHONY: generate-format
generate-format: generate
	@dart format lib/

.PHONY: generate-dev
generate-dev: get l10n format fluttergen ## Generate the code
	@dart run build_runner watch --delete-conflicting-outputs --release


.PHONY: gen
gen: generate

.PHONY: codegen
codegen: generate

# https://pub.dev/packages/flutter_launcher_icons
.PHONY: generate-icons
generate-icons: ## Generate icons for the app
	@dart run flutter_launcher_icons -f flutter_launcher_icons.yaml

# https://pub.dev/packages/flutter_native_splash
.PHONY: generate-splash
generate-splash: ## Generate splash screen for the app
	@dart run flutter_native_splash:create --path=flutter_native_splash.yaml

.PHONY: clean
clean: ## Clean the project and remove all generated files
	@rm -f coverage.*
	@rm -rf dist bin out build
	@rm -rf coverage .dart_tool .packages pubspec.lock

.PHONY: diff
diff: ## git diff
	$(call print-target)
	@git diff --exit-code
	@RES=$$(git status --porcelain) ; if [ -n "$$RES" ]; then echo $$RES && exit 1 ; fi


.PHONY: run-chrome-web-app
run-chrome-web:
	@flutter run -d chrome --web-browser-flag "--disable-web-security" --dart-define-from-file=config/development.json

.PHONY: run-chrome-release-web-app
run-chrome-release-web:
	@flutter run -d chrome --web-browser-flag "--disable-web-security" --dart-define-from-file=config/production.json

.PHONY: build-android-apk
build-android: flutter-clean generate ## Build the android app
	@flutter build apk --release --dart-define-from-file=config/production.json

.PHONY: build-android-appBundle
build-android-appBundle: flutter-clean generate ## Build the android app
	@flutter build appbundle --release --dart-define-from-file=config/production.json

.PHONY: build-windows
build-windows: flutter-clean generate ## Build the windows app
	@flutter build windows --release --dart-define-from-file=config/production.json

.PHONY: build-web
build-web: flutter-clean generate
	@flutter build web --release --dart-define-from-file=config/production.json

.PHONY: firebase-deploy
firebase-deploy: build-web
	@firebase deploy

.PHONY: build-ios
build-ios: flutter-clean generate ## Build the ios app
	@flutter build ios --release --dart-define-from-file=config/production.json

.PHONY: build-macos
build-macos: flutter-clean generate ## Build the macos app
	@flutter build macos --release --dart-define-from-file=config/production.json

.PHONY: build-linux
build-linux: flutter-clean generate ## Build the linux app
	@flutter build linux --release --dart-define-from-file=config/production.json

#	@dart pub global activate flutterfire_cli
#	@flutterfire configure \
#		-i tld.domain.app \
#		-m tld.domain.app \
#		-a tld.domain.app \
#		-p project \
#		-e email@gmail.com \
#		-o lib/src/common/constant/firebase_options.g.dart

# "assets/images/products\/(\d+)\/(\d+)\.jpg"
#downscale-images:
#	@cd assets/datasources/images
#	@find . -name "*.jpg" -exec mogrify -format webp {} \;
#	@find . -name "*.jpeg" -exec mogrify -format webp {} \;
#	@find . -name "*.png" -exec mogrify -format webp {} \;
#	@find . -name "*.jpg" -exec rm -f {} \;
#	@find . -name "*.jpeg" -exec rm -f {} \;
#	@find . -name "*.png" -exec rm -f {} \;
#	@find . -type f \( -name "0.webp" -o -name "1.webp" -o -name "2.webp" -o -name "3.webp" -o -name "4.webp" -o -name "5.webp" -o -name "6.webp" -o -name "7.webp" -o -name "8.webp" -o -name "9.webp" \) -exec mogrify -resize '512x512>' -quality 80 {} \;
#	@find . -name "thumbnail.webp" -exec mogrify -resize '256x256>' -quality 75 {} \;