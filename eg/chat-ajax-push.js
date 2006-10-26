
var poll_count = 0;
var sid = Math.random();

function new_request() {
  var req;
  if (window.XMLHttpRequest) {
    req = new XMLHttpRequest();
  } else if (window.ActiveXObject) {
    req = new ActiveXObject("Microsoft.XMLHTTP");
  } 
  return req;
}

function do_request(url, callback) {
  var req = new_request();
  if(req != undefined) {
    req.onreadystatechange = function() {
      if (req.readyState == 4) { // only if req is "loaded"
        if (req.status == 200) { // only if "OK"
          if(callback) callback(req.responseText);
        } else {
          alert("AJAX Error:\r\n" + req.statusText);
        }
      }
    }
    req.open("GET", url, true);
    req.send("");
  }
}

function setup_poll() {
  setTimeout('poll_server()',100);
}

function poll_server() {
  document.getElementById('status').innerHTML = 'Polling ('+(poll_count++)+')...';
  do_request('pushstream/' + sid + '/' + Math.random(), got_update);
}

function got_update(txt) {
  document.getElementById('status').innerHTML = 'Got update.'
  if(document.getElementById("log").innerHTML != txt)
    document.getElementById("log").innerHTML = txt;
  setup_poll();
}

function message_sent(result) {
  document.getElementById("message").value = "";
  document.getElementById("message").focus();
}

function send_message() {
  var username = document.getElementById("username").value;
  var message = document.getElementById("message").value;
  username = encodeURIComponent(username);
  message = encodeURIComponent(message);
  do_request( sid + '?x=' + Math.random() + '&username=' + username + '&message=' + message, message_sent);
  return false;
}

function init() {
  setup_poll();
  //document.getElementById("sendbutton").onclick = send_message;
  send_message();
  document.getElementById("f").onsubmit = send_message;
  //document.getElementById("username").focus();
}

window.onload = init;

