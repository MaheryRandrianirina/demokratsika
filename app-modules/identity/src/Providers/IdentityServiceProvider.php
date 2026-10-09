<?php

namespace Demokratsika\Identity\Providers;

use Illuminate\Support\ServiceProvider;

class IdentityServiceProvider extends ServiceProvider
{
	public function register(): void
	{
		$this->mergeConfigFrom(
            dirname(__DIR__, 2).'/config/register.php',
            'register'
        );
	}
	
	public function boot(): void
	{
	}
}
