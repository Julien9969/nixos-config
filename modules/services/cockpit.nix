# modules/services/cockpit.nix
{ config, pkgs, ... }:
{
	services.cockpit = {
		enable = true;
		port = 9090;
		openFirewall = true; # Please see the comments section
		settings = {
			WebService = {
				AllowUnencrypted = true;
			};
		};
	};
}