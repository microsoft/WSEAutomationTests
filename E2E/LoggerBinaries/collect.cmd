@rem test for elevated
@net session 1>nul 2>nul || (@echo collecting traces requires elevated rights... & exit /b 1)
 
@tracelog.exe -start AsgTrace -f AsgTrace.etl > AsgTraceLog.txt
@tracelog.exe -systemrundown AsgTrace >> AsgTraceLog.txt
@tracelog.exe -enableex AsgTrace -guid #AB71FE82-3742-446b-982A-1FEDBB7D9594 -level 0xff >> AsgTraceLog.txt
@tracelog.exe -enableex AsgTrace -guid #45AA7AE8-974C-5BBD-D7B5-8EA567DAC172 -level 0xff >> AsgTraceLog.txt
@tracelog.exe -enableex AsgTrace -guid #641CBF19-268C-44B8-9618-16EA1158E54D -level 0xff >> AsgTraceLog.txt
@tracelog.exe -enableex AsgTrace -guid #21f0190b-6273-5306-5451-77ba8481d945 -level 0xff >> AsgTraceLog.txt
@tracelog.exe -enableex AsgTrace -guid #afe60d91-90d2-59bd-ebbf-d321f5691437 -level 0xff >> AsgTraceLog.txt
 
@echo Tracing started. 
@pause >> AsgTraceLog.txt
 
@tracelog -stop AsgTrace >> AsgTraceLog.txt
 
@eprint AsgTrace.etl /o AsgTrace.txt /oftext /time >> AsgTraceLog.txt
@REM type AsgTrace.txt

@echo Please share output files AsgTrace.etl, AsgTrace.txt, and AsgTraceLog.txt