command! -range=% -nargs=* CarrierOpen lua require('carrier.chat').open_chat(<f-args>)
command! -range=% -nargs=* CarrierOpenSplit lua require('carrier.chat').open_chat_split(<f-args>)
command! -range=% -nargs=* CarrierOpenVSplit lua require('carrier.chat').open_chat_vsplit(<f-args>)

command! -range=% -nargs=* CarrierStart lua require('carrier.chat').start_chat(<f-args>)
command! -range=% -nargs=* CarrierStartSplit lua require('carrier.chat').start_chat_split(<f-args>)
command! -range=% -nargs=* CarrierStartVSplit lua require('carrier.chat').start_chat_vsplit(<f-args>)

command! CarrierSendMessage lua require('carrier.chat').send_message()

command! -nargs=1 CarrierSwitchModel lua require('carrier.config').switch_model(<f-args>)
command! -nargs=1 CarrierSetTemperature lua require('carrier.config').set_temperature(<f-args>)
