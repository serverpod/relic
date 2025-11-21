import React from 'react';
import clsx from 'clsx';

function FeatureCard({ title, description, icon }) {
  return (
    <div className={clsx('col col--4')}>
      <div className="card" style={{ height: '100%' }}>
        <div className="card__header">
          <h4>{icon ? `${icon} ${title}` : title}</h4>
        </div>
        <div className="card__body">
          <p>{description}</p>
        </div>
      </div>
    </div>
  );
}

export default function DocFeatureCards({ features }) {
  return (
    <section>
      <div className="container">
        <div className="row" style={{ gap: '1rem 0' }}>
          {features.map((f, idx) => (
            <FeatureCard key={idx} title={f.title} description={f.description} icon={f.icon} />)
          )}
        </div>
      </div>
    </section>
  );
}


