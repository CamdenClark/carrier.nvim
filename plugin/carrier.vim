command! -range=% -nargs=* CarrierLogOpen lua require('carrier.log').open_log(<f-args>)
command! -range=% -nargs=* CarrierLogOpenSplit lua require('carrier.log').open_log_split(<f-args>)
command! -range=% -nargs=* CarrierLogOpenVSplit lua require('carrier.log').open_log_vsplit(<f-args>)

command! CarrierSendMessage lua require('carrier.log').send_message()
command! CarrierStopMessage lua require('carrier.log').stop_message()
command! CarrierQuickMessage lua require('carrier.log').quick_message()
command! CarrierSendDiagnosticMessage lua require('carrier.log').send_diagnostic_help_message()

command! -nargs=1 CarrierSwitchModel lua require('carrier.config').switch_model(<f-args>)

command! -range=% -nargs=* CarrierEditSelection lua require('carrier.edit').edit_selection(<f-args>)
