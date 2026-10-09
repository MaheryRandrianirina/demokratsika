<?php

use Illuminate\Support\Facades\Route;

Route::inertia(config("register.route_path"), "welcome")
    ->name(
        config('register.route_name_prefix') . "index"
    );
