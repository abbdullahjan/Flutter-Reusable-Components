import { useEffect, useState } from 'react';
import { enablePush, disablePush, isPushEnabled } from './push';

export default function PushButton({ userId }) {
  const [on, setOn] = useState(false);
  const [err, setErr] = useState('');

  useEffect(() => { isPushEnabled().then(setOn).catch(() => {}); }, []);

  const toggle = async () => {
    try {
      setErr('');
      on ? await disablePush() : await enablePush(userId);
      setOn(!on);
    } catch (e) { setErr(e.message); }
  };

  return (
    <>
      <button onClick={toggle}>{on ? 'Disable' : 'Enable'} notifications</button>
      {err && <p style={{ color: 'red' }}>{err}</p>}
    </>
  );
}