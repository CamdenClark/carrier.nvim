command! -nargs=1 CarrierSwitchModel lua require('carrier.config').switch_model(<f-args>)

command! -range=% -nargs=* CarrierSuggestEdit lua require('carrier.edit').suggest_edit(<f-args>)
command! -range=% -nargs=* CarrierSuggestAddition lua require('carrier.edit').suggest_addition(<f-args>)
command! CarrierReject lua require('carrier.edit').reject()
command! CarrierAccept lua require('carrier.edit').accept()
command! CarrierCancel lua require('carrier.edit').cancel()
