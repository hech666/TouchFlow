"""Run real UIKit regressions. Preferences base, jbroot, lock state and actions mocked.
This test is NOT a SpringBoard/device gesture test.
"""
from pathlib import Path
import subprocess,json,plistlib,tempfile,time,platform,os
R=Path(__file__).resolve().parents[1];out=R/'packages';out.mkdir(exist_ok=True)
def run(args,**kwargs):return subprocess.check_output(args,text=True,**kwargs).strip()
sdk=run(['xcrun','--sdk','iphonesimulator','--show-sdk-path']);arch='arm64' if platform.machine()=='arm64' else 'x86_64'
devices=json.loads(run(['xcrun','simctl','list','devices','available','-j']))['devices'];candidates=[]
for runtime,rows in devices.items():
 if '.iOS-' not in runtime:continue
 for d in rows:
  if d.get('isAvailable') and d['name'].startswith('iPhone'):candidates.append(d)
assert candidates,'No available iPhone simulator runtime'
device=next((d for d in candidates if d['state']=='Booted'),candidates[0]);udid=device['udid']
if device['state']!='Booted':subprocess.run(['xcrun','simctl','boot',udid],check=True)
subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],check=True)
tmp=Path(tempfile.mkdtemp(prefix='touchflow-ui-'));app=tmp/'TouchFlowUITests.app';app.mkdir();binary=app/'TouchFlowUITests'
sources=['Tests/HaogeTouchFlowUITests.m','Sources/HaogeTouchFlowPanel.m','Sources/HaogeTouchFlowPanelModel.m','Sources/HaogeTouchFlowActionCatalog.m','Sources/HaogeTouchFlowConfig.m','HaogeTouchFlowPrefs/HaogeTouchFlowRootListController.m','HaogeTouchFlowPrefs/HaogeTouchFlowBindingController.m','HaogeTouchFlowPrefs/HaogeTouchFlowPanelSettings.m','HaogeTouchFlowPrefs/HaogeTouchFlowActionPickerController.m']
subprocess.run(['xcrun','clang','-arch',arch,'-isysroot',sdk,'-mios-simulator-version-min=16.0','-fobjc-arc','-fblocks','-Wall','-Wextra','-Werror','-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1','-ITests/Support','-ISources','-IHaogeTouchFlowPrefs','-framework','UIKit','-framework','Foundation','-framework','CoreFoundation','-framework','QuartzCore',*sources,'-o',str(binary)],cwd=R,check=True)
info={'CFBundleExecutable':'TouchFlowUITests','CFBundleIdentifier':'com.haoge.touchflow.uitests','CFBundleName':'TouchFlowUITests','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','LSRequiresIPhoneOS':True,'MinimumOSVersion':'16.0','UILaunchScreen':{},'UIDeviceFamily':[1],'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait']}
info['UIApplicationSceneManifest']={'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[{'UISceneConfigurationName':'TouchFlow UI tests','UISceneDelegateClassName':'HaogeTouchFlowTestApp'}]}}
(app/'Info.plist').write_bytes(plistlib.dumps(info));subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
subprocess.run(['xcrun','simctl','install',udid,str(app)],check=True)
subprocess.run(['xcrun','simctl','launch',udid,'com.haoge.touchflow.uitests'],check=True)
container=Path(run(['xcrun','simctl','get_app_container',udid,'com.haoge.touchflow.uitests','data']));result=container/'Documents/ui_result.json'
for i in range(45):
 if result.exists():break
 time.sleep(1)
assert result.exists(),'UIKit test did not write result; inspect simulator crash log'
report=json.loads(result.read_text());(out/'ui_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False));assert report['success'],report
