# Get true file version of EXE installer
Update-TypeData -TypeName System.Io.FileInfo -MemberType ScriptProperty -MemberName FileVersionUpdated -Value {
    New-Object System.Version -ArgumentList @(
        $this.VersionInfo.FileMajorPart
        $this.VersionInfo.FileMinorPart
        $this.VersionInfo.FileBuildPart
        $this.VersionInfo.FilePrivatePart
    )
} -ErrorAction SilentlyContinue