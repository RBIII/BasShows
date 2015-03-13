var page = 1;

$(window).scroll(function() {
   if($(window).scrollTop() + $(window).height() == $(document).height()) {
     page++;
     $.get('/shows.json?page=' + parseInt(page), function(shows) {

       shows.forEach(function(show) {
         var $divContainer = $('<div>').addClass('show columns small-12 medium-4 text-center panel');

         var $bandName = $('<h3>').addClass('band_name');
         var $ticketLink = $('<a>').attr('href', show.ticket_url).text(show.band);

         var $builtBandName = $bandName.append($ticketLink);
         var $venue = $('<h4>').addClass('venue').text(show.venue);
         var $dateTime = $('<p>').addClass('datetime').text(show.date + " " + show.time);

         $divContainer.append($builtBandName);
         $divContainer.append($venue);
         $divContainer.append($dateTime);

         $('.shows').append($divContainer);
       });
     });
   }
});
