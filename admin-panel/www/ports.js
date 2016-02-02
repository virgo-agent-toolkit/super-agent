Elm.fullscreen(Elm.Main, {
  initialLocation: window.location.search.substring(1)
});

// Listen to output on the location port and pass to browser
Elm.ports.location.subscribe(function (newValue) {
  history.replaceState({}, "", "?" + newValue);
});
