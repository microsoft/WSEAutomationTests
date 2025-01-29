@rem test for elevated
@net session 1>nul 2>nul || (@echo collecting traces requires elevated rights... & exit /b 1)

@tracelog.exe -start AsgTrace -f AsgTrace.etl > AsgTraceLog.txt
@tracelog.exe -systemrundown AsgTrace >> AsgTraceLog.txt
@tracelog.exe -enableex AsgTrace -guid #AB71FE82-3742-446b-982A-1FEDBB7D9594 -level 0xff  >> AsgTraceLog.txt

@echo Tracing started....
@pause >> AsgTraceLog.txt

@tracelog -stop AsgTrace >> AsgTraceLog.txt

@eprint AsgTrace.etl /o AsgTrace.txt /oftext /time >> AsgTraceLog.txt
@REM type AsgTrace.txt

@echo Please share output files AsgTrace.etl, AsgTrace.txt, and AsgTraceLog.txt
