command! -nargs=1 CarrierSwitchModel lua require('carrier.config').switch_model(<f-args>)
command! -range=% -nargs=* CarrierSuggestEdit lua require('carrier.edit').suggest_edit(<f-args>)
command! CarrierRejectEdit lua require('carrier.edit').reject_edit()
command! CarrierAcceptEdit lua require('carrier.edit').accept_edit()
