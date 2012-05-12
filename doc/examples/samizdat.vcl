# Varnish configuration for Samizdat

backend default {
    .host = "127.0.0.1";
    .port = "3000";
}
backend default1 {
    .host = "127.0.0.1";
    .port = "3001";
}
backend default2 {
    .host = "127.0.0.1";
    .port = "3002";
}
backend default3 {
    .host = "127.0.0.1";
    .port = "3003";
}

director default_director round-robin {
    { .backend = default; }
    { .backend = default1; }
    { .backend = default2; }
    { .backend = default3; }
}

sub vcl_recv {
    set req.backend = default_director;
}

sub vcl_fetch {
    set beresp.ttl = 0.5ms;
}
