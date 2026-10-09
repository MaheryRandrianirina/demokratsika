<?php

use App\Models\User;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    config([
        'inertia.ssr.enabled' => true,
        'inertia.ssr.ensure_bundle_exists' => false,
    ]);

    $this->withoutVite();

    Http::fake([
        '*' => Http::response([
            'head' => ['<title>SSR</title>'],
            'body' => '<div id="app">server rendered</div>',
        ]),
    ]);
});

test('public pages are server-side rendered', function (string $routeName) {
    $response = $this->get(route($routeName));

    $response->assertOk();
    $response->assertSee('server rendered', false);
    Http::assertSentCount(1);
})->with(['home', 'login', 'password.request']);

test('authenticated pages are rendered on the client only', function () {
    $this->actingAs(User::factory()->create());

    $response = $this->get(route('dashboard'));

    $response->assertOk();
    $response->assertDontSee('server rendered', false);
    Http::assertNothingSent();
});

test('server-side rendering can be disabled entirely', function () {
    config(['inertia.ssr.enabled' => false]);

    $response = $this->get(route('home'));

    $response->assertOk();
    $response->assertDontSee('server rendered', false);
    Http::assertNothingSent();
});
