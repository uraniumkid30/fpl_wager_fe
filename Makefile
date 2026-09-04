.PHONY: bootstrap run-local run-demo check build-web

API_BASE_URL ?= http://127.0.0.1:8080
PAYMENT_CALLBACK_URL ?= fplwager://payments/callback

bootstrap:
	flutter create . --platforms=android,ios,web
	flutter pub get

run-local:
	flutter run --dart-define=API_BASE_URL=$(API_BASE_URL) --dart-define=PAYMENT_CALLBACK_URL=$(PAYMENT_CALLBACK_URL) --dart-define=ENABLE_DEV_CREDIT=true

run-demo:
	flutter run --dart-define=USE_DEMO_DATA=true

check:
	dart format --output=none --set-exit-if-changed lib test
	flutter analyze
	flutter test

build-web:
	flutter build web --release --dart-define=API_BASE_URL=$(API_BASE_URL) --dart-define=PAYMENT_CALLBACK_URL=$(PAYMENT_CALLBACK_URL)
