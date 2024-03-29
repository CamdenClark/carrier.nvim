command! -range=% -nargs=* CarrierLogOpen lua require('carrier.log').open_log(<f-args>)
command! -range=% -nargs=* CarrierLogOpenSplit lua require('carrier.log').open_log_split(<f-args>)
command! -range=% -nargs=* CarrierLogOpenVSplit lua require('carrier.log').open_log_vsplit(<f-args>)

command! -nargs=? CarrierSendMessage lua require('carrier.log').send_message(<f-args>)
command! CarrierStopMessage lua require('carrier.log').stop_message()

command! -nargs=1 CarrierSwitchModel lua require('carrier.config').switch_model(<f-args>)

command! -range=% -nargs=* CarrierEditSelection lua require('carrier.edit').edit_selection(<f-args>)
