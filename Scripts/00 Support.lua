function trans_new_screen(name)
	SCREENMAN:GetTopScreen():SetNextScreenName(name)
	SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
end
