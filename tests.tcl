
puts [http::get-route-variables {/hello/:name/:town} {/hello/john/smallville}]
puts [http::get-route-variables {/hello/:name/:town} {/hello/john/smallville/}]
puts [http::get-route-variables {/hello/there/:name/:town} {/hello/there/john/smallville/}]
puts [http::get-route-variables {/hello/:name/from/:town} {/hello/john/from/smallville/}]

puts [http::get-route-variables {/bye/:name/:town} {/hello/john/smallville/}]

exit 1
